import 'dart:math' as math;
import 'dart:ui';

import '../models/service.dart';
import 'service_analysis.dart';

class ServiceTopologyLayout {
  final Size size;
  final Map<String, Rect> nodeRects;
  final Map<String, int> nodeRanks;
  final Map<ServiceTopologyEdge, List<Offset>> edgePaths;

  /// Purpose: Create a service topology layout instance.
  /// Inputs: None.
  /// Returns: A new `ServiceTopologyLayout` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
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

  /// Purpose: Calculate node positions and pre-routed edge paths for a topology graph.
  /// Inputs: `graph`, `routes`, `viewportWidth`.
  /// Returns: A `ServiceTopologyLayout` with canvas size, node rectangles, ranks, and edge paths.
  /// Side effects: None.
  /// Notes: Rows are compacted after semantic placement so unused route lanes do not stretch the canvas.
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
    final compactRows = _compactDesiredRows(graph, desiredRows);
    final nodeRects = _placeNodes(graph, nodeRanks, compactRows);

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

  /// Purpose: Place topology nodes into rank columns and compact rows within each rank.
  /// Inputs: `graph`, `nodeRanks`, `desiredRows`.
  /// Returns: Node rectangles keyed by node id.
  /// Side effects: None.
  /// Notes: Rank-local row compaction removes blank vertical bands that only matter to other ranks.
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
      final rankRows = _compactRankRows(nodes, desiredRows);
      final rankWidth = rankWidths[rank] ?? nodeWidth;
      var previousBottom = padding - verticalGap;
      for (final node in nodes) {
        final width = _nodeWidth(node);
        final height = _nodeHeight(node);
        final targetY = padding + (rankRows[node.id] ?? 0) * rowStride;
        final y = math.max(targetY, previousBottom + verticalGap);
        final centeredX = (rankX[rank] ?? padding) + (rankWidth - width) / 2;
        rects[node.id] = Rect.fromLTWH(centeredX, y, width, height);
        previousBottom = y + height;
      }
    }
    return rects;
  }

  /// Purpose: Compact desired rows within one rank before turning them into y positions.
  /// Inputs: `nodes`, `desiredRows`.
  /// Returns: A compact row number for each node in the rank.
  /// Side effects: None.
  /// Notes: Prevents rows used only in other ranks from leaving tall blank bands in this rank.
  static Map<String, double> _compactRankRows(
    List<ServiceTopologyNode> nodes,
    Map<String, double> desiredRows,
  ) {
    final rowMap = _compactRowValueMap(
      nodes.map((node) => desiredRows[node.id]).whereType<double>(),
    );
    return {
      for (final node in nodes)
        node.id: _compactRowValue(desiredRows[node.id] ?? 0, rowMap),
    };
  }

  /// Purpose: Remove row gaps that are only reserved by routes without visible nodes.
  /// Inputs: `graph`, `desiredRows`.
  /// Returns: A compacted desired-row map keyed by node id.
  /// Side effects: None.
  /// Notes: Keeps visible row order while preventing stale or shared route rows from stretching the canvas.
  static Map<String, double> _compactDesiredRows(
    ServiceTopologyGraph graph,
    Map<String, double> desiredRows,
  ) {
    final usedRows =
        graph.nodes
            .map((node) => desiredRows[node.id])
            .whereType<double>()
            .toList()
          ..sort();
    if (usedRows.isEmpty) return desiredRows;

    final compacted = _compactRowValueMap(usedRows);

    return {
      for (final entry in desiredRows.entries)
        entry.key: _compactRowValue(entry.value, compacted),
    };
  }

  /// Purpose: Build a compact value map from sparse desired-row values.
  /// Inputs: `rows`.
  /// Returns: A raw-row to compact-row map.
  /// Side effects: None.
  /// Notes: Large raw gaps collapse while tiny ordering gaps still leave visual breathing room.
  static Map<double, double> _compactRowValueMap(Iterable<double> rows) {
    final uniqueRows = rows.toList()..sort();
    final compactedRows = <double>[];
    for (final row in uniqueRows) {
      if (compactedRows.isEmpty ||
          (row - compactedRows.last).abs() > _rowEpsilon) {
        compactedRows.add(row);
      }
    }

    final compacted = <double, double>{};
    var nextRow = 0.0;
    for (var i = 0; i < compactedRows.length; i++) {
      if (i > 0) {
        final rawGap = compactedRows[i] - compactedRows[i - 1];
        nextRow += rawGap.clamp(0.72, 1.0).toDouble();
      }
      compacted[compactedRows[i]] = nextRow;
    }
    return compacted;
  }

  /// Purpose: Look up a compacted row value for one raw desired row.
  /// Inputs: `row`, `rowMap`.
  /// Returns: The compact row or original value when no match exists.
  /// Side effects: None.
  /// Notes: Floating-point row keys are matched with `_rowEpsilon` tolerance.
  static double _compactRowValue(double row, Map<double, double> rowMap) {
    for (final entry in rowMap.entries) {
      if ((row - entry.key).abs() <= _rowEpsilon) return entry.value;
    }
    return row;
  }

  /// Purpose: Provide the internal node ranks helper for this file.
  /// Inputs: `graph`, `validEdges`.
  /// Returns: `Map<String, int>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal align sibling port ranks helper for this file.
  /// Inputs: `edges`, `nodeMap`, `ranks`.
  /// Returns: `bool`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal node width helper for this file.
  /// Inputs: `node`.
  /// Returns: `double`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static double _nodeWidth(ServiceTopologyNode node) =>
      node.compact ? portChipSize : nodeWidth;

  /// Purpose: Provide the internal node height helper for this file.
  /// Inputs: `node`.
  /// Returns: `double`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static double _nodeHeight(ServiceTopologyNode node) =>
      node.compact ? portChipSize : nodeHeight;

  /// Purpose: Provide the internal route rows helper for this file.
  /// Inputs: `graph`, `routes`, `nodeMap`.
  /// Returns: `Map<String, double>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal desired rows helper for this file.
  /// Inputs: `graph`, `routes`, `routeRows`, `incoming`, plus related optional values from the signature.
  /// Returns: `Map<String, double>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal route edges helper for this file.
  /// Inputs: `validEdges`, `rects`, `ranks`, `size`.
  /// Returns: `Map<ServiceTopologyEdge, List<Offset>>`.
  /// Side effects: None.
  /// Notes: Reuses obstacle-derived routing tracks across edge searches.
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
    final obstacles = [
      for (final rect in rects.values) rect.inflate(_routingClearance),
    ];
    final gridBase = _RoutingGridBase.fromObstacles(obstacles, size);
    final routedSegments = <_Segment>[];
    final paths = <ServiceTopologyEdge, List<Offset>>{};
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
        gridBase: gridBase,
        routedSegments: routedSegments,
        size: size,
      );
      paths[edge] = path;
      routedSegments.addAll(_segmentsForPath(path));
    }
    return paths;
  }

  /// Purpose: Provide the internal port offsets helper for this file.
  /// Inputs: `edges`, `rects`, `ranks`.
  /// Returns: `Map<ServiceTopologyEdge, double>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Route one edge between two node rectangles using the best valid anchor pair.
  /// Inputs: `from`, `to`, anchor offsets, obstacles, `gridBase`, prior routed segments, and `size`.
  /// Returns: A simplified orthogonal polyline, or an empty list when routing fails.
  /// Side effects: None.
  /// Notes: Fast clear candidates are tried before the A* fallback.
  static List<Offset> _routeEdge({
    required Rect from,
    required Rect to,
    required double fromOffset,
    required double toOffset,
    required List<Rect> obstacles,
    required _RoutingGridBase gridBase,
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
    List<Offset>? bestPath;
    var bestScore = double.infinity;
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
      final middle =
          _fastRouteBetween(
            start: startExit,
            goal: endEntry,
            obstacles: obstacles,
            routedSegments: routedSegments,
            size: size,
          ) ??
          _routeBetween(
            start: startExit,
            goal: endEntry,
            obstacles: obstacles,
            gridBase: gridBase,
            routedSegments: routedSegments,
            size: size,
          );
      if (middle == null) continue;
      final path = _simplifyPolyline([
        start,
        startExit,
        ...middle.skip(1),
        end,
      ]);
      final score = _pathScore(path, routedSegments);
      if (score < bestScore) {
        bestScore = score;
        bestPath = path;
      }
    }

    return bestPath ?? const [];
  }

  /// Purpose: Try simple orthogonal edge paths before falling back to A* routing.
  /// Inputs: `start`, `goal`, obstacles, prior routed segments, and `size`.
  /// Returns: A clear simplified polyline, or null when a routed grid search is needed.
  /// Side effects: None.
  /// Notes: Keeps common left-to-right routes cheap while preserving obstacle checks.
  static List<Offset>? _fastRouteBetween({
    required Offset start,
    required Offset goal,
    required List<Rect> obstacles,
    required List<_Segment> routedSegments,
    required Size size,
  }) {
    final candidates = <List<Offset>>[];

    void addCandidate(List<Offset> points) {
      final path = _simplifyPolyline(points.map(_snapOffset).toList());
      if (path.length < 2 || !_pathClear(path, obstacles)) return;
      candidates.add(path);
    }

    if ((start.dx - goal.dx).abs() < _epsilon ||
        (start.dy - goal.dy).abs() < _epsilon) {
      addCandidate([start, goal]);
    }

    addCandidate([start, Offset(goal.dx, start.dy), goal]);
    addCandidate([start, Offset(start.dx, goal.dy), goal]);

    final midX = _snap((start.dx + goal.dx) / 2);
    final midY = _snap((start.dy + goal.dy) / 2);
    addCandidate([start, Offset(midX, start.dy), Offset(midX, goal.dy), goal]);
    addCandidate([start, Offset(start.dx, midY), Offset(goal.dx, midY), goal]);

    final minX = math.min(start.dx, goal.dx);
    final maxX = math.max(start.dx, goal.dx);
    final minY = math.min(start.dy, goal.dy);
    final maxY = math.max(start.dy, goal.dy);
    final leftTrack = _snap((minX - _routingTrackGap).clamp(0.0, size.width));
    final rightTrack = _snap((maxX + _routingTrackGap).clamp(0.0, size.width));
    final topTrack = _snap((minY - _routingTrackGap).clamp(0.0, size.height));
    final bottomTrack = _snap(
      (maxY + _routingTrackGap).clamp(0.0, size.height),
    );
    for (final x in {leftTrack, rightTrack}) {
      addCandidate([start, Offset(x, start.dy), Offset(x, goal.dy), goal]);
    }
    for (final y in {topTrack, bottomTrack}) {
      addCandidate([start, Offset(start.dx, y), Offset(goal.dx, y), goal]);
    }

    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) => _pathScore(
        a,
        routedSegments,
      ).compareTo(_pathScore(b, routedSegments)),
    );
    return candidates.first;
  }

  /// Purpose: Find an obstacle-avoiding orthogonal path between two already-escaped points.
  /// Inputs: `start`, `goal`, obstacles, `gridBase`, prior routed segments, and `size`.
  /// Returns: A simplified polyline or null when no grid path is available.
  /// Side effects: None.
  /// Notes: Reuses obstacle-derived tracks and adds per-edge lanes for cleaner fan-out.
  static List<Offset>? _routeBetween({
    required Offset start,
    required Offset goal,
    required List<Rect> obstacles,
    required _RoutingGridBase gridBase,
    required List<_Segment> routedSegments,
    required Size size,
  }) {
    final xs = {...gridBase.xs};
    final ys = {...gridBase.ys};
    void addX(double value) => xs.add(_snap(value.clamp(0.0, size.width)));
    void addY(double value) => ys.add(_snap(value.clamp(0.0, size.height)));

    for (final point in [start, goal]) {
      addX(point.dx);
      addY(point.dy);
      addX(point.dx - _routingTrackGap);
      addX(point.dx + _routingTrackGap);
      addY(point.dy - _routingTrackGap);
      addY(point.dy + _routingTrackGap);
    }
    for (final segment in routedSegments) {
      addX(segment.a.dx);
      addX(segment.b.dx);
      addY(segment.a.dy);
      addY(segment.b.dy);
      if (segment.vertical) {
        addX(segment.a.dx - _routingTrackGap);
        addX(segment.a.dx + _routingTrackGap);
      }
      if (segment.horizontal) {
        addY(segment.a.dy - _routingTrackGap);
        addY(segment.a.dy + _routingTrackGap);
      }
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

  /// Purpose: Score a routed edge path so competing anchor choices can choose the cleaner route.
  /// Inputs: `path`, `routedSegments`.
  /// Returns: A lower score for shorter paths with fewer turns and less congestion.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static double _pathScore(List<Offset> path, List<_Segment> routedSegments) {
    if (path.length < 2) return double.infinity;
    var score = 0.0;
    var previousDirection = 0;
    for (var i = 1; i < path.length; i++) {
      final a = path[i - 1];
      final b = path[i];
      score += _manhattan(a, b);
      score += _congestionCost(a, b, routedSegments);
      final direction = (a.dx - b.dx).abs() < _epsilon ? 2 : 1;
      if (previousDirection != 0 && previousDirection != direction) {
        score += 26.0;
      }
      previousDirection = direction;
    }
    return score;
  }

  /// Purpose: Check whether every segment in a candidate polyline avoids obstacles.
  /// Inputs: `path`, `obstacles`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Used by the fast router before accepting a non-A* path.
  static bool _pathClear(List<Offset> path, List<Rect> obstacles) {
    if (path.length < 2) return false;
    for (var i = 1; i < path.length; i++) {
      if (_segmentBlocked(path[i - 1], path[i], obstacles)) return false;
    }
    return true;
  }

  /// Purpose: Provide the internal stub blocked helper for this file.
  /// Inputs: `a`, `b`, `obstacles`.
  /// Returns: `bool`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal segment blocked helper for this file.
  /// Inputs: `a`, `b`, `obstacles`.
  /// Returns: `bool`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Score how much a candidate segment conflicts with already routed segments.
  /// Inputs: `a`, `b`, `routedSegments`.
  /// Returns: `double`.
  /// Side effects: None.
  /// Notes: Hardly penalizes crossings, strongly penalizes reused lanes, and softly penalizes nearby parallel lanes.
  static double _congestionCost(
    Offset a,
    Offset b,
    List<_Segment> routedSegments,
  ) {
    var cost = 0.0;
    final candidate = _Segment(a, b);
    for (final segment in routedSegments) {
      if (candidate.sameAxisOverlap(segment)) {
        cost += 180.0;
      } else if (candidate.nearAxisOverlap(segment, _routingTrackGap * 0.85)) {
        cost += 58.0;
      } else if (candidate.crosses(segment)) {
        cost += 28.0;
      }
    }
    return cost;
  }

  /// Purpose: Provide the internal segments for path helper for this file.
  /// Inputs: `path`.
  /// Returns: `List<_Segment>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static List<_Segment> _segmentsForPath(List<Offset> path) {
    final segments = <_Segment>[];
    for (var i = 1; i < path.length; i++) {
      if ((path[i] - path[i - 1]).distance > _epsilon) {
        segments.add(_Segment(path[i - 1], path[i]));
      }
    }
    return segments;
  }

  /// Purpose: Provide the internal simplify polyline helper for this file.
  /// Inputs: `points`.
  /// Returns: `List<Offset>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal anchor helper for this file.
  /// Inputs: `rect`, `side`, `yOffset`.
  /// Returns: `Offset`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Offset _anchor(Rect rect, _TopologySide side, double yOffset) =>
      switch (side) {
        _TopologySide.left => Offset(rect.left, rect.center.dy + yOffset),
        _TopologySide.right => Offset(rect.right, rect.center.dy + yOffset),
      };

  /// Purpose: Provide the internal side vector helper for this file.
  /// Inputs: None.
  /// Returns: `Offset`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Offset _sideVector(_TopologySide side) => switch (side) {
    _TopologySide.left => const Offset(-1, 0),
    _TopologySide.right => const Offset(1, 0),
  };

  /// Purpose: Provide the internal edge span helper for this file.
  /// Inputs: `edge`, `rects`.
  /// Returns: `double`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static double _edgeSpan(ServiceTopologyEdge edge, Map<String, Rect> rects) {
    final from = rects[edge.from];
    final to = rects[edge.to];
    if (from == null || to == null) return 0;
    return (to.center - from.center).distance;
  }

  /// Purpose: Provide the internal service node id helper for this file.
  /// Inputs: `serviceId`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static String _serviceNodeId(String serviceId) => 'service:$serviceId';

  /// Purpose: Provide the internal compare routes for layout helper for this file.
  /// Inputs: `a`, `b`.
  /// Returns: `int`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal lane order helper for this file.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static int _laneOrder(ServiceAccessLane lane) => switch (lane) {
    ServiceAccessLane.local => 0,
    ServiceAccessLane.vpn => 1,
    ServiceAccessLane.public => 2,
  };

  /// Purpose: Provide the internal lane rank helper for this file.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static int _laneRank(ServiceAccessLane? lane) => switch (lane) {
    ServiceAccessLane.local => 0,
    ServiceAccessLane.vpn => 1,
    ServiceAccessLane.public => 2,
    null => 3,
  };

  /// Purpose: Provide the internal route method name helper for this file.
  /// Inputs: `route`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static String _routeMethodName(ServiceRoute route) =>
      route.hops
          .map((hop) => hop.method?.name)
          .whereType<String>()
          .firstOrNull ??
      '';

  /// Purpose: Provide the internal median helper for this file.
  /// Inputs: `values`.
  /// Returns: `double`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static double _median(List<double> values) {
    final ordered = [...values]..sort();
    final middle = ordered.length ~/ 2;
    if (ordered.length.isOdd) return ordered[middle];
    return (ordered[middle - 1] + ordered[middle]) / 2;
  }

  /// Purpose: Provide the internal role order helper for this file.
  /// Inputs: `node`.
  /// Returns: `int`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal lane bucket helper for this file.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static int _laneBucket(ServiceTopologyNode node) => switch (node.lane) {
    ServiceAccessLane.local => 0,
    ServiceAccessLane.vpn => 1,
    ServiceAccessLane.public => 2,
    null => -1,
  };

  /// Purpose: Provide the internal manhattan helper for this file.
  /// Inputs: `a`, `b`.
  /// Returns: `double`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static double _manhattan(Offset a, Offset b) =>
      (a.dx - b.dx).abs() + (a.dy - b.dy).abs();

  /// Purpose: Provide the internal snap offset helper for this file.
  /// Inputs: `offset`.
  /// Returns: `Offset`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Offset _snapOffset(Offset offset) =>
      Offset(_snap(offset.dx), _snap(offset.dy));

  /// Purpose: Provide the internal clamp offset helper for this file.
  /// Inputs: `offset`.
  /// Returns: `Offset`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Offset _clampOffset(Offset offset, Size size) => Offset(
    offset.dx.clamp(0.0, size.width).toDouble(),
    offset.dy.clamp(0.0, size.height).toDouble(),
  );

  /// Purpose: Provide the internal snap helper for this file.
  /// Inputs: `value`.
  /// Returns: `double`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static double _snap(num value) => (value.toDouble() * 2).roundToDouble() / 2;

  /// Purpose: Provide the internal same rect helper for this file.
  /// Inputs: `a`, `b`.
  /// Returns: `bool`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static bool _sameRect(Rect a, Rect b) =>
      (a.left - b.left).abs() < _epsilon &&
      (a.top - b.top).abs() < _epsilon &&
      (a.right - b.right).abs() < _epsilon &&
      (a.bottom - b.bottom).abs() < _epsilon;
}

enum _TopologySide { left, right }

const _epsilon = 0.01;
const _rowEpsilon = 0.0001;

class _RoutingGridBase {
  final Set<double> xs;
  final Set<double> ys;

  /// Purpose: Create a reusable routing grid base.
  /// Inputs: `xs`, `ys`.
  /// Returns: A new `_RoutingGridBase` instance.
  /// Side effects: None.
  /// Notes: Stores obstacle-derived tracks shared by all edge A* searches.
  const _RoutingGridBase({required this.xs, required this.ys});

  /// Purpose: Build shared routing tracks from node obstacles and canvas size.
  /// Inputs: `obstacles`, `size`.
  /// Returns: A `_RoutingGridBase` with reusable x and y track sets.
  /// Side effects: None.
  /// Notes: Omits obstacle center tracks to keep A* grids smaller.
  factory _RoutingGridBase.fromObstacles(List<Rect> obstacles, Size size) {
    final xs = <double>{};
    final ys = <double>{};
    void addX(double value) =>
        xs.add(ServiceTopologyLayout._snap(value.clamp(0.0, size.width)));
    void addY(double value) =>
        ys.add(ServiceTopologyLayout._snap(value.clamp(0.0, size.height)));

    addX(ServiceTopologyLayout.padding / 2);
    addX(size.width - ServiceTopologyLayout.padding / 2);
    addY(ServiceTopologyLayout.padding / 2);
    addY(size.height - ServiceTopologyLayout.padding / 2);
    for (final obstacle in obstacles) {
      addX(obstacle.left - ServiceTopologyLayout._routingTrackGap);
      addX(obstacle.right + ServiceTopologyLayout._routingTrackGap);
      addY(obstacle.top - ServiceTopologyLayout._routingTrackGap);
      addY(obstacle.bottom + ServiceTopologyLayout._routingTrackGap);
    }
    return _RoutingGridBase(xs: xs, ys: ys);
  }
}

class _Segment {
  final Offset a;
  final Offset b;

  /// Purpose: Create a segment instance.
  /// Inputs: `a`, `b`.
  /// Returns: A new `_Segment` instance.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  const _Segment(this.a, this.b);

  bool get horizontal => (a.dy - b.dy).abs() < _epsilon;

  bool get vertical => (a.dx - b.dx).abs() < _epsilon;

  /// Purpose: Implement the same axis overlap behavior for this file.
  /// Inputs: `other`.
  /// Returns: `bool`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
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

  /// Purpose: Check whether two parallel segments run close enough to look bundled.
  /// Inputs: `other`, `distance`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Used as a soft routing penalty, not as an obstacle.
  bool nearAxisOverlap(_Segment other, double distance) {
    if (horizontal &&
        other.horizontal &&
        (a.dy - other.a.dy).abs() <= distance) {
      return _rangesOverlap(a.dx, b.dx, other.a.dx, other.b.dx);
    }
    if (vertical && other.vertical && (a.dx - other.a.dx).abs() <= distance) {
      return _rangesOverlap(a.dy, b.dy, other.a.dy, other.b.dy);
    }
    return false;
  }

  /// Purpose: Implement the crosses behavior for this file.
  /// Inputs: `other`.
  /// Returns: `bool`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
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

  /// Purpose: Provide the internal ranges overlap helper for this file.
  /// Inputs: `a1`, `a2`, `b1`, `b2`.
  /// Returns: `bool`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static bool _rangesOverlap(double a1, double a2, double b1, double b2) {
    final aMin = math.min(a1, a2);
    final aMax = math.max(a1, a2);
    final bMin = math.min(b1, b2);
    final bMax = math.max(b1, b2);
    return math.max(aMin, bMin) < math.min(aMax, bMax) - _epsilon;
  }

  /// Purpose: Provide the internal between helper for this file.
  /// Inputs: `value`, `start`, `end`.
  /// Returns: `bool`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static bool _between(double value, double start, double end) {
    final minValue = math.min(start, end) - _epsilon;
    final maxValue = math.max(start, end) + _epsilon;
    return value >= minValue && value <= maxValue;
  }
}

class _RouteState {
  final int index;
  final double cost;

  /// Purpose: Create a route state instance.
  /// Inputs: `index`, `cost`.
  /// Returns: A new `_RouteState` instance.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  const _RouteState(this.index, this.cost);
}

class _RouteHeap {
  final _items = <_RouteState>[];

  /// Purpose: Return whether not empty is true.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isNotEmpty => _items.isNotEmpty;

  /// Purpose: Add the requested value through the current flow.
  /// Inputs: `state`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  void add(_RouteState state) {
    _items.add(state);
    _bubbleUp(_items.length - 1);
  }

  /// Purpose: Implement the remove first behavior for this file.
  /// Inputs: None.
  /// Returns: `_RouteState`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  _RouteState removeFirst() {
    final first = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      _bubbleDown(0);
    }
    return first;
  }

  /// Purpose: Provide the internal bubble up helper for this file.
  /// Inputs: `index`.
  /// Returns: `void`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  void _bubbleUp(int index) {
    while (index > 0) {
      final parent = (index - 1) >> 1;
      if (_items[parent].cost <= _items[index].cost) break;
      _swap(parent, index);
      index = parent;
    }
  }

  /// Purpose: Provide the internal bubble down helper for this file.
  /// Inputs: `index`.
  /// Returns: `void`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal swap helper for this file.
  /// Inputs: `a`, `b`.
  /// Returns: `void`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  void _swap(int a, int b) {
    final temp = _items[a];
    _items[a] = _items[b];
    _items[b] = temp;
  }
}
