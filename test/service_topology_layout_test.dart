import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/services/services/service_analysis.dart';
import 'package:my_device/features/services/services/service_topology_layout.dart';
import 'package:my_device/features/services/views/service_topology_widgets.dart';

import 'support/topology_fixtures.dart';

/// Purpose: Register the test cases defined in this file.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: This serves as the test entry point for the file.
void main() {
  test('topology layout renders port nodes as square chips', () {
    final graph = buildSampleGraph();
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
      final graph = buildSampleGraph();
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
    final graph = buildSparseRouteGraph();
    final layout = ServiceTopologyLayout.build(graph.graph, graph.routes, 640);

    final appA = layout.nodeRects['service:app-a']!;
    final appB = layout.nodeRects['service:app-b']!;

    expect((appB.top - appA.top).abs(), lessThan(180));
  });

  test('topology router keeps edge paths out of unrelated node rectangles', () {
    final graph = buildSampleGraph();
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
    final data = frpTopologyData();
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
    final data = frpTopologyData();
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
    final data = chipRowsData();
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
    const stride =
        ServiceTopologyLayout.portChipSize + ServiceTopologyLayout.rowGap;
    expect(stride, lessThan(ServiceTopologyLayout.nodeHeight + 44));
    expect(chips[1].top - chips[0].top, closeTo(stride, 0.01));
    expect(chips[2].top - chips[1].top, closeTo(stride, 0.01));
    expect(
      layout.nodeRects['service:app']!.center.dy,
      closeTo(chips[1].center.dy, 0.01),
      reason: 'the service is centred on its chips',
    );
  });

  test('domain sinks share the last rank and paths stay clean', () {
    for (final sample in [buildSampleGraph(), frpSample()]) {
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

    final sample = buildSampleGraph();
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
    final shared = sharedVpsSample();
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
      buildSampleGraph(),
      buildSparseRouteGraph(),
      frpSample(),
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
    for (final sample in [buildSampleGraph(), frpSample(), sharedVpsSample()]) {
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
    final sample = frpSample();
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

  test('no two edges share a line and parallel tracks keep their spacing', () {
    for (final sample in [
      homelabSample(),
      buildSampleGraph(),
      frpSample(),
      sharedVpsSample(),
      syntheticSample(),
    ]) {
      for (final group in [false, true]) {
        final layout = ServiceTopologyLayout.build(
          sample.graph,
          sample.routes,
          900,
          options: ServiceTopologyLayoutOptions(groupByDevice: group),
        );
        _expectCleanPaths(sample.graph, layout);
        _expectSeparateLines(layout, reason: 'grouped: $group');
      }
    }
  });

  test('a port chip sits beside its service', () {
    for (final sample in [homelabSample(), frpSample(), sharedVpsSample()]) {
      for (final group in [false, true]) {
        final layout = ServiceTopologyLayout.build(
          sample.graph,
          sample.routes,
          900,
          options: ServiceTopologyLayoutOptions(groupByDevice: group),
        );
        final chipsOf = <String, List<String>>{};
        for (final edge in sample.graph.edges) {
          final from = _node(sample.graph, edge.from);
          final to = _node(sample.graph, edge.to);
          if (from.kind == ServiceTopologyNodeKind.service &&
              to.compact &&
              (to.kind == ServiceTopologyNodeKind.remoteEntry ||
                  to.serviceId == from.serviceId)) {
            chipsOf.putIfAbsent(edge.from, () => []).add(edge.to);
          }
        }
        for (final entry in chipsOf.entries) {
          if (entry.value.length != 1) continue;
          expect(
            layout.nodeRects[entry.value.single]!.center.dy,
            closeTo(layout.nodeRects[entry.key]!.center.dy, 1),
            reason: '${entry.value.single} beside ${entry.key} ($group)',
          );
        }
      }
    }

    final homelab = homelabSample();
    final layout = ServiceTopologyLayout.build(
      homelab.graph,
      homelab.routes,
      900,
      options: const ServiceTopologyLayoutOptions(groupByDevice: true),
    );
    for (final service in [
      'jellyfin',
      'nextcloud',
      'vaultwarden',
      'wordpress',
    ]) {
      final edge = homelab.graph.edges.singleWhere(
        (edge) =>
            edge.from == 'service:$service' &&
            edge.to == 'endpoint:$service:web',
      );
      expect(layout.edgePaths[edge], hasLength(2), reason: service);
    }
  });

  test('domains sit beside what leads to them, not below the containers', () {
    final homelab = homelabSample();
    final layout = ServiceTopologyLayout.build(
      homelab.graph,
      homelab.routes,
      900,
      options: const ServiceTopologyLayoutOptions(groupByDevice: true),
    );
    double centre(String id) => layout.nodeRects[id]!.center.dy;
    const stride =
        ServiceTopologyLayout.nodeHeight + ServiceTopologyLayout.rowGap;
    for (final domain in [
      'domain:mac-mini.tail1234.ts.net',
      'domain:mac-mini.et.example.net',
    ]) {
      expect(
        (centre(domain) - centre('service:tailscale')).abs(),
        lessThanOrEqualTo(stride / 2 + 0.01),
        reason: domain,
      );
    }
    final entry = layout.nodeRects.keys.singleWhere(
      (id) => id.startsWith('remote:'),
    );
    for (final domain in ['domain:example.com', 'domain:cloud.example.com']) {
      expect(
        (centre(domain) - centre(entry)).abs(),
        lessThanOrEqualTo(stride / 2 + 0.01),
        reason: domain,
      );
    }
  });

  test('the edge painter rounds bends and keeps both ends', () {
    final path = topologyEdgePath(const [
      Offset(0, 0),
      Offset(100, 0),
      Offset(100, 100),
    ]);
    final metric = path.computeMetrics().single;
    expect(metric.length, closeTo(200 - 12 + math.pi * 3, 0.5));
    expect(metric.getTangentForOffset(0)!.position, Offset.zero);
    expect(
      metric.getTangentForOffset(metric.length)!.position,
      const Offset(100, 100),
    );
    final jog = topologyEdgePath(const [
      Offset(0, 0),
      Offset(50, 0),
      Offset(50, 4),
      Offset(100, 4),
    ]).computeMetrics().single;
    expect(jog.length, lessThan(104), reason: 'a 4 px jog keeps a 2 px radius');
  });

  test('a 60-node, 80-edge graph lays out', () {
    final sample = syntheticSample();
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

/// Purpose: Check that no two drawn edges run along one line and that
/// parallel vertical segments of different edges keep the track spacing.
/// Inputs: `layout`, `reason`.
/// Returns: None.
/// Side effects: Records test expectations.
/// Notes: Vertical segments are what `_nudgeSegments` spreads apart; a
/// horizontal pair is only required not to coincide.
void _expectSeparateLines(ServiceTopologyLayout layout, {String reason = ''}) {
  final segments = <({int edge, Offset a, Offset b})>[];
  for (final (index, path) in layout.edgePaths.values.indexed) {
    for (var i = 1; i < path.length; i++) {
      segments.add((edge: index, a: path[i - 1], b: path[i]));
    }
  }
  for (var i = 0; i < segments.length; i++) {
    for (var j = i + 1; j < segments.length; j++) {
      final s = segments[i];
      final t = segments[j];
      if (s.edge == t.edge) continue;
      final sv = _vertical(s.a, s.b) && !_horizontal(s.a, s.b);
      final tv = _vertical(t.a, t.b) && !_horizontal(t.a, t.b);
      final sh = _horizontal(s.a, s.b) && !_vertical(s.a, s.b);
      final th = _horizontal(t.a, t.b) && !_vertical(t.a, t.b);
      if (sv && tv && _rangesOverlap(s.a.dy, s.b.dy, t.a.dy, t.b.dy)) {
        final gap = (s.a.dx - t.a.dx).abs();
        expect(
          gap < 0.01 || gap >= 4,
          isTrue,
          reason: '$reason: verticals ${s.a}-${s.b} and ${t.a}-${t.b}',
        );
        expect(gap, greaterThan(0.01), reason: '$reason: shared vertical');
      }
      if (sh && th && _rangesOverlap(s.a.dx, s.b.dx, t.a.dx, t.b.dx)) {
        expect(
          (s.a.dy - t.a.dy).abs(),
          greaterThan(0.01),
          reason: '$reason: shared horizontal ${s.a}-${s.b}, ${t.a}-${t.b}',
        );
      }
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
