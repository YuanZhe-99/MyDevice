import 'dart:math' as math;
import 'dart:ui';

import '../models/service.dart';
import 'service_analysis.dart';

class ServiceTopologyLayout {
  final Size size;
  final Map<String, Rect> nodeRects;
  final Map<String, int> nodeRanks;
  final Map<ServiceTopologyEdge, List<Offset>> edgePaths;

  const ServiceTopologyLayout({
    required this.size,
    required this.nodeRects,
    required this.nodeRanks,
    required this.edgePaths,
  });

  static const nodeWidth = 204.0;
  static const nodeHeight = 76.0;
  static const portChipSize = 52.0;
  static const rankGap = 38.0;
  static const verticalGap = 24.0;
  static const padding = 24.0;
  static const _routingMargin = 72.0;
  static const _routingClearance = 14.0;
  static const _routingEscape = 18.0;
  static const _routingTrackGap = 22.0;

  static ServiceTopologyLayout build(
    ServiceTopologyGraph graph,
    List<ServiceRoute> routes,
    double viewportWidth,
  ) {
    final nodeMap = {for (final node in graph.nodes) node.id: node};
    final validEdges = graph.edges
        .where(
          (edge) =>
              nodeMap.containsKey(edge.from) && nodeMap.containsKey(edge.to),
        )
        .toList();
    final incoming = <String, Set<String>>{};
    final outgoing = <String, Set<String>>{};
    for (final node in graph.nodes) {
      incoming[node.id] = <String>{};
      outgoing[node.id] = <String>{};
    }
    for (final edge in validEdges) {
      outgoing[edge.from]!.add(edge.to);
      incoming[edge.to]!.add(edge.from);
    }

    final routeRows = _routeRows(graph, routes, nodeMap);
    final desiredRows = _desiredRows(
      graph,
      routes,
      routeRows,
      incoming,
      outgoing,
    );
    final nodeRanks = _nodeRanks(graph, validEdges);
    final nodeRects = _placeNodes(graph, nodeRanks, desiredRows);

    var maxRight = padding;
    var maxBottom = padding;
    for (final rect in nodeRects.values) {
      maxRight = math.max(maxRight, rect.right);
      maxBottom = math.max(maxBottom, rect.bottom);
    }
    final size = Size(
      math.max(viewportWidth, maxRight + padding + _routingMargin),
      math.max(360.0, maxBottom + padding + _routingMargin),
    );
    final edgePaths = _routeEdges(validEdges, nodeRects, nodeRanks, size);

    return ServiceTopologyLayout(
      size: size,
      nodeRects: nodeRects,
      nodeRanks: nodeRanks,
      edgePaths: edgePaths,
    );
  }

  static Map<String, Rect> _placeNodes(
    ServiceTopologyGraph graph,
    Map<String, int> nodeRanks,
    Map<String, double> desiredRows,
  ) {
    final ranked = <int, List<ServiceTopologyNode>>{};
    for (final node in graph.nodes) {
      ranked.putIfAbsent(nodeRanks[node.id] ?? 0, () => []).add(node);
    }
    final orderedRanks = ranked.keys.toList()..sort();
    for (final nodes in ranked.values) {
      nodes.sort((a, b) {
        final rowCmp = (desiredRows[a.id] ?? 0).compareTo(
          desiredRows[b.id] ?? 0,
        );
        if (rowCmp != 0) return rowCmp;

        final roleCmp = _roleOrder(a).compareTo(_roleOrder(b));
        if (roleCmp != 0) return roleCmp;

        final laneCmp = _laneBucket(a).compareTo(_laneBucket(b));
        if (laneCmp != 0) return laneCmp;

        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
    }

    final rankWidths = <int, double>{};
    for (final entry in ranked.entries) {
      rankWidths[entry.key] = entry.value.fold<double>(
        0,
        (width, node) => math.max(width, _nodeWidth(node)),
      );
    }

    final rankX = <int, double>{};
    var x = padding;
    for (final rank in orderedRanks) {
      rankX[rank] = x;
      x += (rankWidths[rank] ?? nodeWidth) + rankGap;
    }

    final rects = <String, Rect>{};
    const rowStride = nodeHeight + 44;
    for (final rank in orderedRanks) {
      final nodes = ranked[rank] ?? const <ServiceTopologyNode>[];
      final rankWidth = rankWidths[rank] ?? nodeWidth;
      var previousBottom = padding - verticalGap;
      for (final node in nodes) {
        final width = _nodeWidth(node);
        final height = _nodeHeight(node);
        final targetY = padding + (desiredRows[node.id] ?? 0) * rowStride;
        final y = math.max(targetY, previousBottom + verticalGap);
        final centeredX = (rankX[rank] ?? padding) + (rankWidth - width) / 2;
        rects[node.id] = Rect.fromLTWH(centeredX, y, width, height);
        previousBottom = y + height;
      }
    }
    return rects;
  }

  static Map<String, int> _nodeRanks(
    ServiceTopologyGraph graph,
    List<ServiceTopologyEdge> validEdges,
  ) {
    final nodeMap = {for (final node in graph.nodes) node.id: node};
    final ranks = <String, int>{
      for (final node in graph.nodes)
        node.id: node.kind == ServiceTopologyNodeKind.device ? 0 : 1,
    };
    final rankLimit = math.max(2, graph.nodes.length + 1);
    for (var iteration = 0; iteration < graph.nodes.length + 2; iteration++) {
      var changed = false;
      for (final edge in validEdges) {
        final fromRank = ranks[edge.from] ?? 0;
        final nextRank = math.min(rankLimit, fromRank + 1);
        if (nextRank > (ranks[edge.to] ?? 0)) {
          ranks[edge.to] = nextRank;
          changed = true;
        }
      }
      if (_alignSiblingPortRanks(validEdges, nodeMap, ranks)) {
        changed = true;
      }
      if (!changed) break;
    }

    final uniqueRanks = ranks.values.toSet().toList()..sort();
    final compressed = {
      for (var i = 0; i < uniqueRanks.length; i++) uniqueRanks[i]: i,
    };
    return {
      for (final entry in ranks.entries)
        entry.key: compressed[entry.value] ?? 0,
    };
  }

  static bool _alignSiblingPortRanks(
    List<ServiceTopologyEdge> edges,
    Map<String, ServiceTopologyNode> nodeMap,
    Map<String, int> ranks,
  ) {
    final servicePorts = <String, Set<String>>{};
    for (final edge in edges) {
      final from = nodeMap[edge.from];
      final to = nodeMap[edge.to];
      if (from?.kind != ServiceTopologyNodeKind.service || to == null) {
        continue;
      }
      final portLike =
          to.compact &&
          (to.kind == ServiceTopologyNodeKind.endpoint ||
              to.kind == ServiceTopologyNodeKind.remoteEntry);
      if (!portLike) continue;
      servicePorts.putIfAbsent(edge.from, () => <String>{}).add(edge.to);
    }

    var changed = false;
    for (final portIds in servicePorts.values) {
      if (portIds.length < 2) continue;
      final targetRank = portIds.fold<int>(
        0,
        (rank, id) => math.max(rank, ranks[id] ?? 0),
      );
      for (final id in portIds) {
        if ((ranks[id] ?? 0) < targetRank) {
          ranks[id] = targetRank;
          changed = true;
        }
      }
    }
    return changed;
  }

  static double _nodeWidth(ServiceTopologyNode node) =>
      node.compact ? portChipSize : nodeWidth;

  static double _nodeHeight(ServiceTopologyNode node) =>
      node.compact ? portChipSize : nodeHeight;

  static Map<String, double> _routeRows(
    ServiceTopologyGraph graph,
    List<ServiceRoute> routes,
    Map<String, ServiceTopologyNode> nodeMap,
  ) {
    final routesBySource = <String, List<ServiceRoute>>{};
    for (final route in routes) {
      routesBySource
          .putIfAbsent(_serviceNodeId(route.sourceServiceId), () => [])
          .add(route);
    }

    final sourceIds = <String>{
      ...routesBySource.keys,
      for (final node in graph.nodes)
        if (node.kind == ServiceTopologyNodeKind.service &&
            node.role == ServiceTopologyNodeRole.localService)
          node.id,
    }.toList();
    sourceIds.sort((a, b) {
      final aNode = nodeMap[a];
      final bNode = nodeMap[b];
      final aLabel = aNode?.label.toLowerCase() ?? a;
      final bLabel = bNode?.label.toLowerCase() ?? b;
      return aLabel.compareTo(bLabel);
    });

    final rows = <String, double>{};
    var row = 0.0;
    for (final sourceId in sourceIds) {
      final sourceRoutes = routesBySource[sourceId] ?? const <ServiceRoute>[];
      if (sourceRoutes.isEmpty) {
        row += 1.35;
        continue;
      }
      final orderedRoutes = [...sourceRoutes]..sort(_compareRoutesForLayout);
      for (final route in orderedRoutes) {
        rows[route.id] = row;
        row += 1;
      }
      row += 0.38;
    }
    return rows;
  }

  static Map<String, double> _desiredRows(
    ServiceTopologyGraph graph,
    List<ServiceRoute> routes,
    Map<String, double> routeRows,
    Map<String, Set<String>> incoming,
    Map<String, Set<String>> outgoing,
  ) {
    final sourceRouteRows = <String, List<double>>{};
    for (final route in routes) {
      final row = routeRows[route.id];
      if (row == null) continue;
      sourceRouteRows
          .putIfAbsent(_serviceNodeId(route.sourceServiceId), () => [])
          .add(row);
    }

    final desired = <String, double>{};
    for (final node in graph.nodes) {
      final scores = <double>[];
      for (final routeId in node.routeIds) {
        final row = routeRows[routeId];
        if (row != null) scores.add(row);
      }
      if (node.kind == ServiceTopologyNodeKind.service) {
        scores.addAll(sourceRouteRows[node.id] ?? const <double>[]);
      }
      if (scores.isNotEmpty) desired[node.id] = _median(scores);
    }

    for (var iteration = 0; iteration < 10; iteration++) {
      var changed = false;
      for (final node in graph.nodes) {
        if (desired.containsKey(node.id)) continue;
        final scores = <double>[];
        for (final neighborId in {
          ...?incoming[node.id],
          ...?outgoing[node.id],
        }) {
          final score = desired[neighborId];
          if (score != null) scores.add(score);
        }
        if (scores.isEmpty) continue;
        desired[node.id] = _median(scores);
        changed = true;
      }
      if (!changed) break;
    }

    var fallbackRow = desired.values.isEmpty
        ? 0.0
        : desired.values.reduce(math.max) + 1;
    final fallbackNodes =
        graph.nodes.where((node) => !desired.containsKey(node.id)).toList()
          ..sort((a, b) {
            final roleCmp = _roleOrder(a).compareTo(_roleOrder(b));
            if (roleCmp != 0) return roleCmp;
            return a.label.toLowerCase().compareTo(b.label.toLowerCase());
          });
    for (final node in fallbackNodes) {
      desired[node.id] = fallbackRow;
      fallbackRow += 1;
    }
    return desired;
  }

  static Map<ServiceTopologyEdge, List<Offset>> _routeEdges(
    List<ServiceTopologyEdge> validEdges,
    Map<String, Rect> rects,
    Map<String, int> ranks,
    Size size,
  ) {
    final outgoingOffsets = _portOffsets(
      validEdges,
      rects,
      ranks,
      outgoing: true,
    );
    final incomingOffsets = _portOffsets(
      validEdges,
      rects,
      ranks,
      outgoing: false,
    );
    final routedSegments = <_Segment>[];
    final paths = <ServiceTopologyEdge, List<Offset>>{};
    final obstacles = [
      for (final rect in rects.values) rect.inflate(_routingClearance),
    ];
    final orderedEdges = [...validEdges]
      ..sort((a, b) {
        final spanCmp = _edgeSpan(b, rects).compareTo(_edgeSpan(a, rects));
        if (spanCmp != 0) return spanCmp;
        final laneCmp = _laneRank(a.lane).compareTo(_laneRank(b.lane));
        if (laneCmp != 0) return laneCmp;
        return '${a.from}->${a.to}'.compareTo('${b.from}->${b.to}');
      });

    for (final edge in orderedEdges) {
      final from = rects[edge.from];
      final to = rects[edge.to];
      if (from == null || to == null) continue;
      final path = _routeEdge(
        from: from,
        to: to,
        fromOffset: outgoingOffsets[edge] ?? 0,
        toOffset: incomingOffsets[edge] ?? 0,
        obstacles: obstacles,
        routedSegments: routedSegments,
        size: size,
      );
      paths[edge] = path;
      routedSegments.addAll(_segmentsForPath(path));
    }
    return paths;
  }

  static Map<ServiceTopologyEdge, double> _portOffsets(
    List<ServiceTopologyEdge> edges,
    Map<String, Rect> rects,
    Map<String, int> ranks, {
    required bool outgoing,
  }) {
    final grouped = <String, List<ServiceTopologyEdge>>{};
    for (final edge in edges) {
      grouped.putIfAbsent(outgoing ? edge.from : edge.to, () => []).add(edge);
    }

    final offsets = <ServiceTopologyEdge, double>{};
    for (final entry in grouped.entries) {
      final nodeRect = rects[entry.key];
      final maxOffset = nodeRect == null
          ? 0.0
          : math.max(0.0, nodeRect.height / 2 - 12);
      final nodeEdges = entry.value
        ..sort((a, b) {
          final aPeer = outgoing ? rects[a.to] : rects[a.from];
          final bPeer = outgoing ? rects[b.to] : rects[b.from];
          final yCmp = (aPeer?.center.dy ?? 0).compareTo(bPeer?.center.dy ?? 0);
          if (yCmp != 0) return yCmp;
          final rankCmp = ((outgoing ? ranks[a.to] : ranks[a.from]) ?? 0)
              .compareTo((outgoing ? ranks[b.to] : ranks[b.from]) ?? 0);
          if (rankCmp != 0) return rankCmp;
          return '${a.from}->${a.to}'.compareTo('${b.from}->${b.to}');
        });

      final midpoint = (nodeEdges.length - 1) / 2;
      for (var i = 0; i < nodeEdges.length; i++) {
        offsets[nodeEdges[i]] = ((i - midpoint) * 9.0)
            .clamp(-maxOffset, maxOffset)
            .toDouble();
      }
    }
    return offsets;
  }

  static List<Offset> _routeEdge({
    required Rect from,
    required Rect to,
    required double fromOffset,
    required double toOffset,
    required List<Rect> obstacles,
    required List<_Segment> routedSegments,
    required Size size,
  }) {
    final forward = to.center.dx >= from.center.dx;
    final sameRank = (to.center.dx - from.center.dx).abs() < 8;
    final side = sameRank && from.center.dx > size.width / 2
        ? _TopologySide.left
        : _TopologySide.right;
    final startSide = sameRank
        ? side
        : (forward ? _TopologySide.right : _TopologySide.left);
    final endSide = sameRank
        ? side
        : (forward ? _TopologySide.left : _TopologySide.right);
    final candidates = <({_TopologySide start, _TopologySide end})>[];
    void addCandidate(_TopologySide start, _TopologySide end) {
      final candidate = (start: start, end: end);
      if (!candidates.any(
        (existing) => existing.start == start && existing.end == end,
      )) {
        candidates.add(candidate);
      }
    }

    addCandidate(startSide, endSide);
    addCandidate(_TopologySide.right, _TopologySide.left);
    addCandidate(_TopologySide.left, _TopologySide.right);
    addCandidate(_TopologySide.right, _TopologySide.right);
    addCandidate(_TopologySide.left, _TopologySide.left);

    final fromObstacle = from.inflate(_routingClearance);
    final toObstacle = to.inflate(_routingClearance);
    for (final candidate in candidates) {
      final start = _snapOffset(_anchor(from, candidate.start, fromOffset));
      final end = _snapOffset(_anchor(to, candidate.end, toOffset));
      final startExit = _snapOffset(
        _clampOffset(
          start + _sideVector(candidate.start) * _routingEscape,
          size,
        ),
      );
      final endEntry = _snapOffset(
        _clampOffset(end + _sideVector(candidate.end) * _routingEscape, size),
      );
      if (_stubBlocked(start, startExit, obstacles, allowed: fromObstacle) ||
          _stubBlocked(endEntry, end, obstacles, allowed: toObstacle)) {
        continue;
      }
      final middle = _routeBetween(
        start: startExit,
        goal: endEntry,
        obstacles: obstacles,
        routedSegments: routedSegments,
        size: size,
      );
      if (middle == null) continue;
      return _simplifyPolyline([start, startExit, ...middle.skip(1), end]);
    }

    return const [];
  }

  static List<Offset>? _routeBetween({
    required Offset start,
    required Offset goal,
    required List<Rect> obstacles,
    required List<_Segment> routedSegments,
    required Size size,
  }) {
    final xs = <double>{};
    final ys = <double>{};
    void addX(double value) => xs.add(_snap(value.clamp(0.0, size.width)));
    void addY(double value) => ys.add(_snap(value.clamp(0.0, size.height)));

    addX(padding / 2);
    addX(size.width - padding / 2);
    addY(padding / 2);
    addY(size.height - padding / 2);
    for (final point in [start, goal]) {
      addX(point.dx);
      addY(point.dy);
    }
    for (final obstacle in obstacles) {
      addX(obstacle.left - _routingTrackGap);
      addX(obstacle.right + _routingTrackGap);
      addX(obstacle.center.dx);
      addY(obstacle.top - _routingTrackGap);
      addY(obstacle.bottom + _routingTrackGap);
      addY(obstacle.center.dy);
    }

    final xValues = xs.toList()..sort();
    final yValues = ys.toList()..sort();
    final startX = xValues.indexOf(_snap(start.dx));
    final startY = yValues.indexOf(_snap(start.dy));
    final goalX = xValues.indexOf(_snap(goal.dx));
    final goalY = yValues.indexOf(_snap(goal.dy));
    if (startX < 0 || startY < 0 || goalX < 0 || goalY < 0) {
      return null;
    }

    final pointCount = xValues.length * yValues.length;
    final distances = List<double>.filled(pointCount * 3, double.infinity);
    final previous = List<int?>.filled(pointCount * 3, null);
    final heap = _RouteHeap();

    int pointIndex(int x, int y) => y * xValues.length + x;
    int stateIndex(int point, int direction) => point * 3 + direction;
    Offset pointOffset(int point) => Offset(
      xValues[point % xValues.length],
      yValues[point ~/ xValues.length],
    );

    final startPoint = pointIndex(startX, startY);
    final goalPoint = pointIndex(goalX, goalY);
    final startState = stateIndex(startPoint, 0);
    distances[startState] = 0;
    heap.add(_RouteState(startState, _manhattan(start, goal)));

    int? bestGoalState;
    while (heap.isNotEmpty) {
      final current = heap.removeFirst();
      final currentCost = distances[current.index];
      final currentPoint = current.index ~/ 3;
      final currentDirection = current.index % 3;
      if (currentPoint == goalPoint) {
        bestGoalState = current.index;
        break;
      }

      final x = currentPoint % xValues.length;
      final y = currentPoint ~/ xValues.length;
      final neighbors = <({int x, int y, int direction})>[
        if (x > 0) (x: x - 1, y: y, direction: 1),
        if (x < xValues.length - 1) (x: x + 1, y: y, direction: 1),
        if (y > 0) (x: x, y: y - 1, direction: 2),
        if (y < yValues.length - 1) (x: x, y: y + 1, direction: 2),
      ];
      final a = pointOffset(currentPoint);
      for (final neighbor in neighbors) {
        final nextPoint = pointIndex(neighbor.x, neighbor.y);
        final b = pointOffset(nextPoint);
        if (_segmentBlocked(a, b, obstacles)) continue;
        final turnCost =
            currentDirection == 0 || currentDirection == neighbor.direction
            ? 0.0
            : 26.0;
        final congestionCost = _congestionCost(a, b, routedSegments);
        final nextCost =
            currentCost + _manhattan(a, b) + turnCost + congestionCost;
        final nextState = stateIndex(nextPoint, neighbor.direction);
        if (nextCost + _epsilon >= distances[nextState]) continue;
        distances[nextState] = nextCost;
        previous[nextState] = current.index;
        heap.add(_RouteState(nextState, nextCost + _manhattan(b, goal)));
      }
    }

    if (bestGoalState == null) return null;
    final reversed = <Offset>[];
    int? state = bestGoalState;
    while (state != null) {
      reversed.add(pointOffset(state ~/ 3));
      state = previous[state];
    }
    return _simplifyPolyline(reversed.reversed.toList());
  }

  static bool _stubBlocked(
    Offset a,
    Offset b,
    List<Rect> obstacles, {
    required Rect allowed,
  }) {
    for (final obstacle in obstacles) {
      if (_sameRect(obstacle, allowed)) continue;
      if (_segmentBlocked(a, b, [obstacle])) return true;
    }
    return false;
  }

  static bool _segmentBlocked(Offset a, Offset b, List<Rect> obstacles) {
    if ((a.dx - b.dx).abs() > _epsilon && (a.dy - b.dy).abs() > _epsilon) {
      return true;
    }
    final rect = Rect.fromLTRB(
      math.min(a.dx, b.dx),
      math.min(a.dy, b.dy),
      math.max(a.dx, b.dx),
      math.max(a.dy, b.dy),
    ).inflate(0.6);
    return obstacles.any(rect.overlaps);
  }

  static double _congestionCost(
    Offset a,
    Offset b,
    List<_Segment> routedSegments,
  ) {
    var cost = 0.0;
    final candidate = _Segment(a, b);
    for (final segment in routedSegments) {
      if (candidate.sameAxisOverlap(segment)) {
        cost += 72.0;
      } else if (candidate.crosses(segment)) {
        cost += 24.0;
      }
    }
    return cost;
  }

  static List<_Segment> _segmentsForPath(List<Offset> path) {
    final segments = <_Segment>[];
    for (var i = 1; i < path.length; i++) {
      if ((path[i] - path[i - 1]).distance > _epsilon) {
        segments.add(_Segment(path[i - 1], path[i]));
      }
    }
    return segments;
  }

  static List<Offset> _simplifyPolyline(List<Offset> points) {
    final deduped = <Offset>[];
    for (final point in points) {
      if (deduped.isEmpty || (deduped.last - point).distance > _epsilon) {
        deduped.add(point);
      }
    }
    if (deduped.length < 3) return deduped;
    final simplified = <Offset>[deduped.first];
    for (var i = 1; i < deduped.length - 1; i++) {
      final previous = simplified.last;
      final current = deduped[i];
      final next = deduped[i + 1];
      final horizontal =
          (previous.dy - current.dy).abs() < _epsilon &&
          (current.dy - next.dy).abs() < _epsilon;
      final vertical =
          (previous.dx - current.dx).abs() < _epsilon &&
          (current.dx - next.dx).abs() < _epsilon;
      if (!horizontal && !vertical) simplified.add(current);
    }
    simplified.add(deduped.last);
    return simplified;
  }

  static Offset _anchor(Rect rect, _TopologySide side, double yOffset) =>
      switch (side) {
        _TopologySide.left => Offset(rect.left, rect.center.dy + yOffset),
        _TopologySide.right => Offset(rect.right, rect.center.dy + yOffset),
      };

  static Offset _sideVector(_TopologySide side) => switch (side) {
    _TopologySide.left => const Offset(-1, 0),
    _TopologySide.right => const Offset(1, 0),
  };

  static double _edgeSpan(ServiceTopologyEdge edge, Map<String, Rect> rects) {
    final from = rects[edge.from];
    final to = rects[edge.to];
    if (from == null || to == null) return 0;
    return (to.center - from.center).distance;
  }

  static String _serviceNodeId(String serviceId) => 'service:$serviceId';

  static int _compareRoutesForLayout(ServiceRoute a, ServiceRoute b) {
    final laneCmp = _laneOrder(
      serviceAccessLaneForRoute(a),
    ).compareTo(_laneOrder(serviceAccessLaneForRoute(b)));
    if (laneCmp != 0) return laneCmp;

    final methodCmp = (_routeMethodName(a)).compareTo(_routeMethodName(b));
    if (methodCmp != 0) return methodCmp;

    return serviceRouteDisplayTarget(
      a,
    ).toLowerCase().compareTo(serviceRouteDisplayTarget(b).toLowerCase());
  }

  static int _laneOrder(ServiceAccessLane lane) => switch (lane) {
    ServiceAccessLane.local => 0,
    ServiceAccessLane.vpn => 1,
    ServiceAccessLane.public => 2,
  };

  static int _laneRank(ServiceAccessLane? lane) => switch (lane) {
    ServiceAccessLane.local => 0,
    ServiceAccessLane.vpn => 1,
    ServiceAccessLane.public => 2,
    null => 3,
  };

  static String _routeMethodName(ServiceRoute route) =>
      route.hops
          .map((hop) => hop.method?.name)
          .whereType<String>()
          .firstOrNull ??
      '';

  static double _median(List<double> values) {
    final ordered = [...values]..sort();
    final middle = ordered.length ~/ 2;
    if (ordered.length.isOdd) return ordered[middle];
    return (ordered[middle - 1] + ordered[middle]) / 2;
  }

  static int _roleOrder(ServiceTopologyNode node) {
    if (node.kind == ServiceTopologyNodeKind.endpoint &&
        node.role == ServiceTopologyNodeRole.remoteService) {
      return 8;
    }
    return switch (node.role) {
      ServiceTopologyNodeRole.localDevice => 0,
      ServiceTopologyNodeRole.localService => 1,
      ServiceTopologyNodeRole.localEndpoint => 2,
      ServiceTopologyNodeRole.lanAccess => 3,
      ServiceTopologyNodeRole.vpnAccess => 4,
      ServiceTopologyNodeRole.publicRelay => 5,
      ServiceTopologyNodeRole.remoteDevice => 6,
      ServiceTopologyNodeRole.remoteService => 7,
      ServiceTopologyNodeRole.remotePublicEntry => 9,
      ServiceTopologyNodeRole.domain => 10,
    };
  }

  static int _laneBucket(ServiceTopologyNode node) => switch (node.lane) {
    ServiceAccessLane.local => 0,
    ServiceAccessLane.vpn => 1,
    ServiceAccessLane.public => 2,
    null => -1,
  };

  static double _manhattan(Offset a, Offset b) =>
      (a.dx - b.dx).abs() + (a.dy - b.dy).abs();

  static Offset _snapOffset(Offset offset) =>
      Offset(_snap(offset.dx), _snap(offset.dy));

  static Offset _clampOffset(Offset offset, Size size) => Offset(
    offset.dx.clamp(0.0, size.width).toDouble(),
    offset.dy.clamp(0.0, size.height).toDouble(),
  );

  static double _snap(num value) => (value.toDouble() * 2).roundToDouble() / 2;

  static bool _sameRect(Rect a, Rect b) =>
      (a.left - b.left).abs() < _epsilon &&
      (a.top - b.top).abs() < _epsilon &&
      (a.right - b.right).abs() < _epsilon &&
      (a.bottom - b.bottom).abs() < _epsilon;
}

enum _TopologySide { left, right }

const _epsilon = 0.01;

class _Segment {
  final Offset a;
  final Offset b;

  const _Segment(this.a, this.b);

  bool get horizontal => (a.dy - b.dy).abs() < _epsilon;

  bool get vertical => (a.dx - b.dx).abs() < _epsilon;

  bool sameAxisOverlap(_Segment other) {
    if (horizontal &&
        other.horizontal &&
        (a.dy - other.a.dy).abs() < _epsilon) {
      return _rangesOverlap(a.dx, b.dx, other.a.dx, other.b.dx);
    }
    if (vertical && other.vertical && (a.dx - other.a.dx).abs() < _epsilon) {
      return _rangesOverlap(a.dy, b.dy, other.a.dy, other.b.dy);
    }
    return false;
  }

  bool crosses(_Segment other) {
    if (horizontal && other.vertical) {
      return _between(other.a.dx, a.dx, b.dx) &&
          _between(a.dy, other.a.dy, other.b.dy);
    }
    if (vertical && other.horizontal) {
      return _between(a.dx, other.a.dx, other.b.dx) &&
          _between(other.a.dy, a.dy, b.dy);
    }
    return false;
  }

  static bool _rangesOverlap(double a1, double a2, double b1, double b2) {
    final aMin = math.min(a1, a2);
    final aMax = math.max(a1, a2);
    final bMin = math.min(b1, b2);
    final bMax = math.max(b1, b2);
    return math.max(aMin, bMin) < math.min(aMax, bMax) - _epsilon;
  }

  static bool _between(double value, double start, double end) {
    final minValue = math.min(start, end) - _epsilon;
    final maxValue = math.max(start, end) + _epsilon;
    return value >= minValue && value <= maxValue;
  }
}

class _RouteState {
  final int index;
  final double cost;

  const _RouteState(this.index, this.cost);
}

class _RouteHeap {
  final _items = <_RouteState>[];

  bool get isNotEmpty => _items.isNotEmpty;

  void add(_RouteState state) {
    _items.add(state);
    _bubbleUp(_items.length - 1);
  }

  _RouteState removeFirst() {
    final first = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      _bubbleDown(0);
    }
    return first;
  }

  void _bubbleUp(int index) {
    while (index > 0) {
      final parent = (index - 1) >> 1;
      if (_items[parent].cost <= _items[index].cost) break;
      _swap(parent, index);
      index = parent;
    }
  }

  void _bubbleDown(int index) {
    while (true) {
      final left = index * 2 + 1;
      final right = left + 1;
      var smallest = index;
      if (left < _items.length && _items[left].cost < _items[smallest].cost) {
        smallest = left;
      }
      if (right < _items.length && _items[right].cost < _items[smallest].cost) {
        smallest = right;
      }
      if (smallest == index) break;
      _swap(index, smallest);
      index = smallest;
    }
  }

  void _swap(int a, int b) {
    final temp = _items[a];
    _items[a] = _items[b];
    _items[b] = temp;
  }
}
