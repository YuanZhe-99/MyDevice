import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_share_service.dart';
import '../../../shared/utils/detail_layout.dart';
import '../../devices/models/device.dart';
import '../../devices/widgets/device_category_icon.dart';
import '../models/service.dart';
import '../services/service_access_patterns.dart';
import '../services/service_analysis.dart';
import '../services/service_labels.dart';
import '../services/service_topology_layout.dart';
import 'service_topology_widgets.dart';

enum _TopologyInteractionMode { select, move }

/// Smallest zoom the move mode's viewer allows.
const _minScale = 0.35;

/// Largest zoom the move mode's viewer allows.
const _maxScale = 2.4;

/// How far, in canvas pixels, the move mode's viewer lets the canvas be
/// panned past its edges.
const _boundaryMargin = 180.0;

class _ServiceTopologyView extends StatefulWidget {
  final ServiceTopologyGraph graph;
  final List<ServiceNode> services;
  final List<Device> devices;
  final List<ServiceRoute> routes;
  final ServiceTopologyLayoutOptions options;
  final _TopologyInteractionMode mode;
  final int quarterTurns;
  final GlobalKey? repaintBoundaryKey;
  final ValueChanged<bool>? onLayoutReadyChanged;
  final ServiceTopologyHighlight? highlight;
  final String? selectedNodeId;
  final ValueChanged<ServiceTopologyNode>? onNodeTap;
  final VoidCallback? onBackgroundTap;
  final TransformationController? transformationController;

  /// Purpose: Create the topology canvas.
  /// Inputs: `graph` and the `services`, `devices` and `routes` it was built
  /// from; `options` — the layout switches; `mode`; `quarterTurns`;
  /// `repaintBoundaryKey` — wraps the canvas for export;
  /// `onLayoutReadyChanged`; `highlight` and `selectedNodeId` — the
  /// selection to draw; `onNodeTap`, `onBackgroundTap` — the select-mode
  /// taps; `transformationController` — the move-mode viewer's transform.
  /// Returns: A new `_ServiceTopologyView`.
  /// Side effects: None.
  /// Notes: The state caches the expensive layout per request, so a new
  /// selection only repaints.
  const _ServiceTopologyView({
    super.key,
    required this.graph,
    required this.services,
    required this.devices,
    required this.routes,
    this.options = const ServiceTopologyLayoutOptions(),
    this.mode = _TopologyInteractionMode.select,
    this.quarterTurns = 0,
    this.repaintBoundaryKey,
    this.onLayoutReadyChanged,
    this.highlight,
    this.selectedNodeId,
    this.onNodeTap,
    this.onBackgroundTap,
    this.transformationController,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `_ServiceTopologyViewState` instance.
  /// Side effects: None.
  /// Notes: The state defers layout work until after the route can paint.
  @override
  State<_ServiceTopologyView> createState() => _ServiceTopologyViewState();
}

class _ServiceTopologyViewState extends State<_ServiceTopologyView> {
  ServiceTopologyLayout? _layout;
  _TopologyLayoutRequest? _completedRequest;
  _TopologyLayoutRequest? _pendingRequest;
  bool? _reportedLayoutReady;
  int _layoutGeneration = 0;

  /// The view's size at the last build, which [fitToViewport] fits into.
  Size? _viewport;

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Schedules asynchronous layout work when viewport inputs
  /// change; remembers the viewport size.
  /// Notes: Keeps expensive topology layout out of the first synchronous page
  /// build.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        final turns = widget.quarterTurns % 4;
        final viewportWidth = turns.isOdd && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : constraints.maxWidth;
        final request = _TopologyLayoutRequest(
          graph: widget.graph,
          routes: widget.routes,
          viewportWidth: viewportWidth.round(),
          options: widget.options,
        );
        final ready = _completedRequest == request && _layout != null;
        if (!ready) _ensureLayout(request);
        _reportLayoutReady(ready);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            child: ready
                ? _buildViewer(context, _layout!, turns)
                : _buildLoading(),
          ),
        );
      },
    );
  }

  /// Purpose: Schedule layout computation for the requested topology inputs.
  /// Inputs: `request`.
  /// Returns: None.
  /// Side effects: Updates cached layout state after asynchronous computation finishes.
  /// Notes: Multiple rebuilds for the same request share one pending computation.
  void _ensureLayout(_TopologyLayoutRequest request) {
    if (_pendingRequest == request) return;
    _pendingRequest = request;
    final generation = ++_layoutGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateLayout(request, generation);
    });
  }

  /// Purpose: Calculate and cache a topology layout for one request.
  /// Inputs: `request`, `generation`.
  /// Returns: None.
  /// Side effects: Updates widget state and triggers a rebuild when still current.
  /// Notes: Runs after the first frame so the topology page can show immediately.
  Future<void> _calculateLayout(
    _TopologyLayoutRequest request,
    int generation,
  ) async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted ||
        generation != _layoutGeneration ||
        _pendingRequest != request) {
      return;
    }
    final layout = ServiceTopologyLayout.build(
      request.graph,
      request.routes,
      request.viewportWidth.toDouble(),
      options: request.options,
    );
    if (!mounted ||
        generation != _layoutGeneration ||
        _pendingRequest != request) {
      return;
    }
    setState(() {
      _layout = layout;
      _completedRequest = request;
      _pendingRequest = null;
    });
  }

  /// Purpose: Build the loading placeholder shown while topology layout is calculated.
  /// Inputs: None.
  /// Returns: A lightweight loading widget.
  /// Side effects: None.
  /// Notes: Avoids heavy work in the first route transition frame.
  Widget _buildLoading() {
    return const Center(
      child: SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2.6),
      ),
    );
  }

  /// Purpose: Report whether the current topology layout can be captured or exported.
  /// Inputs: `ready`.
  /// Returns: None.
  /// Side effects: Calls the parent readiness callback after the current frame.
  /// Notes: The callback is deferred so build remains side-effect-free.
  void _reportLayoutReady(bool ready) {
    if (_reportedLayoutReady == ready) return;
    _reportedLayoutReady = ready;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onLayoutReadyChanged?.call(ready);
    });
  }

  /// Purpose: Fit the laid-out canvas into the view.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: Sets the transformation controller's value.
  /// Notes: Uses `fitTransform` with the viewer's own zoom limits and pan
  /// margin, on the canvas as rotated. Does nothing before the first layout
  /// or without a controller.
  void fitToViewport() {
    final layout = _layout;
    final viewport = _viewport;
    final controller = widget.transformationController;
    if (layout == null || viewport == null || controller == null) return;
    final canvas = (widget.quarterTurns % 4).isOdd
        ? Size(layout.size.height, layout.size.width)
        : layout.size;
    controller.value = fitTransform(
      canvas,
      viewport,
      minScale: _minScale,
      maxScale: _maxScale,
      boundaryMargin: _boundaryMargin,
    );
  }

  /// Purpose: Build the canvas — edges, node cards — in its viewer.
  /// Inputs: `context`, `layout`, `turns` — quarter turns, 0 to 3.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Select mode scrolls the canvas and wires node taps and a tap on
  /// the background (keyed `topology-canvas`); move mode drops the taps and
  /// hands the canvas to an `InteractiveViewer` on the page's transform.
  /// With a highlight, the nodes it leaves out are dimmed and the painter
  /// fades their edges. A device node heading a container is drawn as a
  /// header strip; the painter draws the containers under the edges. The
  /// repaint boundary wraps the rotated canvas, so an export shows the
  /// highlight and the containers.
  Widget _buildViewer(
    BuildContext context,
    ServiceTopologyLayout layout,
    int turns,
  ) {
    final select = widget.mode == _TopologyInteractionMode.select;
    final highlight = widget.highlight;
    final onNodeTap = widget.onNodeTap;
    Widget canvas = SizedBox.fromSize(
      size: layout.size,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: ServiceTopologyEdgePainter(
                graph: widget.graph,
                layout: layout,
                colorScheme: Theme.of(context).colorScheme,
                highlight: highlight,
              ),
            ),
          ),
          for (final node in widget.graph.nodes)
            if (layout.nodeRects[node.id] != null)
              Positioned.fromRect(
                rect: layout.nodeRects[node.id]!,
                child: ServiceTopologyNodeCard(
                  key: ValueKey('topology-node-${node.id}'),
                  node: node,
                  icon: iconForTopologyNode(
                    node,
                    widget.services,
                    widget.devices,
                  ),
                  selected: node.id == widget.selectedNodeId,
                  header: layout.groupRects.containsKey(node.id),
                  dimmed:
                      highlight != null && !highlight.nodeIds.contains(node.id),
                  onTap: select && onNodeTap != null
                      ? () => onNodeTap(node)
                      : null,
                ),
              ),
        ],
      ),
    );
    if (turns != 0) {
      canvas = RotatedBox(quarterTurns: turns, child: canvas);
    }
    if (widget.repaintBoundaryKey != null) {
      canvas = RepaintBoundary(key: widget.repaintBoundaryKey, child: canvas);
    }
    if (select) {
      return GestureDetector(
        key: const Key('topology-canvas'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onBackgroundTap,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(child: canvas),
        ),
      );
    }
    return InteractiveViewer(
      transformationController: widget.transformationController,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(_boundaryMargin),
      minScale: _minScale,
      maxScale: _maxScale,
      child: canvas,
    );
  }
}

class _TopologyLayoutRequest {
  final ServiceTopologyGraph graph;
  final List<ServiceRoute> routes;
  final int viewportWidth;
  final ServiceTopologyLayoutOptions options;

  /// Purpose: Create a topology layout request cache key.
  /// Inputs: `graph`, `routes`, `viewportWidth`, `options`.
  /// Returns: A new `_TopologyLayoutRequest` instance.
  /// Side effects: None.
  /// Notes: Uses graph and route list identity so mode-only rebuilds reuse
  /// the cached layout; the options compare by value, so flipping a layout
  /// switch re-lays out the same graph without rebuilding it.
  const _TopologyLayoutRequest({
    required this.graph,
    required this.routes,
    required this.viewportWidth,
    required this.options,
  });

  /// Purpose: Compare layout request keys for cache reuse.
  /// Inputs: `other`.
  /// Returns: Whether both requests describe the same layout inputs.
  /// Side effects: None.
  /// Notes: Viewport width is rounded to avoid tiny constraint jitter causing re-layout.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TopologyLayoutRequest &&
          identical(other.graph, graph) &&
          identical(other.routes, routes) &&
          other.viewportWidth == viewportWidth &&
          other.options == options;

  /// Purpose: Produce a hash for the layout request cache key.
  /// Inputs: None.
  /// Returns: An integer hash code.
  /// Side effects: None.
  /// Notes: Matches the equality contract: graph identity, route identity,
  /// viewport width and options.
  @override
  int get hashCode => Object.hash(
    identityHashCode(graph),
    identityHashCode(routes),
    viewportWidth,
    options,
  );
}

/// The full-screen service topology: the graph with a select and a move
/// mode, route highlighting for a selected node, filters, a legend,
/// rotation, and PNG export.
///
/// Pushed on the root navigator by the Services overview's topology card with
/// a graph built from the current inventory.
class ServiceTopologyPage extends StatefulWidget {
  final ServiceTopologyGraph graph;
  final List<ServiceNode> services;
  final List<Device> devices;
  final List<ServiceRoute> routes;
  final ValueChanged<ServiceNode> onEditService;
  final ValueChanged<ServiceRoute> onEditRoute;
  final Future<void> Function({ServiceAccessDraft? draft}) onAddAccess;

  /// Purpose: Create the full-screen topology page.
  /// Inputs: `graph` — the topology of `services`, `routes` and `devices`;
  /// `onEditService`, `onEditRoute`, `onAddAccess` — the Services page's editors,
  /// offered from the node details.
  /// Returns: A new `ServiceTopologyPage`.
  /// Side effects: None.
  /// Notes: The page never writes storage itself; the callbacks do.
  const ServiceTopologyPage({
    super.key,
    required this.graph,
    required this.services,
    required this.devices,
    required this.routes,
    required this.onEditService,
    required this.onEditRoute,
    required this.onAddAccess,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `_ServiceTopologyPageState`.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<ServiceTopologyPage> createState() => _ServiceTopologyPageState();
}

class _ServiceTopologyPageState extends State<ServiceTopologyPage> {
  _TopologyInteractionMode _mode = _TopologyInteractionMode.select;
  final _captureKey = GlobalKey();
  final _viewKey = GlobalKey<_ServiceTopologyViewState>();
  final _transform = TransformationController();
  int _quarterTurns = 0;
  bool _exporting = false;
  bool _layoutReady = false;
  bool _legendOpen = false;

  /// Whether devices are drawn as containers. Session state, on by default.
  bool _groupByDevice = true;
  ServiceTopologyFilter _filter = const ServiceTopologyFilter();
  String? _selectedNodeId;

  /// The one related route the highlight is narrowed to, if any.
  String? _focusedRouteId;

  /// The graph and routes built for the last active filter.
  ({
    ServiceTopologyFilter filter,
    ServiceTopologyGraph graph,
    List<ServiceRoute> routes,
  })?
  _filtered;

  /// The selection resolved on the last graph it was asked for.
  ({
    ServiceTopologyGraph graph,
    String nodeId,
    String? focus,
    List<ServiceRoute> related,
    ServiceTopologyHighlight highlight,
  })?
  _lit;

  /// Purpose: Release the transformation controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the controller.
  /// Notes: None.
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// Purpose: Return the graph and routes the current filter shows.
  /// Inputs: None.
  /// Returns: The page's own `graph` and `routes` when the filter narrows
  /// nothing; otherwise the graph built from `filterServiceTopologyInput`.
  /// Side effects: Caches the filtered graph in `_filtered`.
  /// Notes: The same instances come back until the filter changes, so the
  /// view's identity-keyed layout cache keeps hitting.
  ({ServiceTopologyGraph graph, List<ServiceRoute> routes}) _visible() {
    if (!_filter.isActive) return (graph: widget.graph, routes: widget.routes);
    final cached = _filtered;
    if (cached != null && cached.filter == _filter) {
      return (graph: cached.graph, routes: cached.routes);
    }
    final input = filterServiceTopologyInput(
      services: widget.services,
      routes: widget.routes,
      filter: _filter,
    );
    final graph = buildServiceTopology(
      services: input.services,
      routes: input.routes,
      devices: widget.devices,
    );
    _filtered = (filter: _filter, graph: graph, routes: input.routes);
    return (graph: graph, routes: input.routes);
  }

  /// Purpose: Resolve the selection on the visible graph.
  /// Inputs: `graph`, `routes` — from `_visible`.
  /// Returns: The selected node, its related routes and the highlight; null
  /// when nothing is selected or the filters hide the selected node.
  /// Side effects: Caches the result in `_lit`.
  /// Notes: Keyed by graph identity, node and focused route, so the painter
  /// keeps one highlight instance while the selection stands. A focused route
  /// that is no longer related falls back to all related routes.
  ({
    ServiceTopologyNode node,
    List<ServiceRoute> related,
    ServiceTopologyHighlight highlight,
  })?
  _selectionIn(ServiceTopologyGraph graph, List<ServiceRoute> routes) {
    final id = _selectedNodeId;
    if (id == null) return null;
    final node = graph.nodes.where((node) => node.id == id).firstOrNull;
    if (node == null) return null;
    final memo = _lit;
    if (memo != null &&
        identical(memo.graph, graph) &&
        memo.nodeId == id &&
        memo.focus == _focusedRouteId) {
      return (node: node, related: memo.related, highlight: memo.highlight);
    }
    final related = relatedRoutesForNode(
      node,
      routes,
      services: widget.services,
    );
    final focused = [
      for (final route in related)
        if (route.id == _focusedRouteId) route,
    ];
    final highlight = serviceTopologyHighlight(
      graph,
      focused.isEmpty ? related : focused,
      selectedNodeId: id,
    );
    _lit = (
      graph: graph,
      nodeId: id,
      focus: _focusedRouteId,
      related: related,
      highlight: highlight,
    );
    return (node: node, related: related, highlight: highlight);
  }

  /// Purpose: Select a tapped node.
  /// Inputs: `node`.
  /// Returns: `void`.
  /// Side effects: Updates the selection; on a window without the details
  /// pane, opens the details sheet.
  /// Notes: The selection lives in the page, so its highlight stays after the
  /// sheet closes.
  void _selectNode(ServiceTopologyNode node) {
    setState(() {
      _selectedNodeId = node.id;
      _focusedRouteId = null;
    });
    final size = MediaQuery.sizeOf(context);
    if (!useDetailTwoPane(size.width, size.height)) _showDetailsSheet(node);
  }

  /// Purpose: Clear the selection.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: Updates widget state.
  /// Notes: Called from a tap on the empty canvas, the selection chip and the
  /// details pane's close button.
  void _clearSelection() {
    if (_selectedNodeId == null && _focusedRouteId == null) return;
    setState(() {
      _selectedNodeId = null;
      _focusedRouteId = null;
    });
  }

  /// Purpose: Narrow the highlight to one route, or widen it back.
  /// Inputs: `route`.
  /// Returns: `void`.
  /// Side effects: Updates widget state.
  /// Notes: Tapping the focused route again widens the highlight to every
  /// related route.
  void _toggleRouteFocus(ServiceRoute route) {
    setState(
      () => _focusedRouteId = _focusedRouteId == route.id ? null : route.id,
    );
  }

  /// Purpose: Apply a new filter.
  /// Inputs: `filter`.
  /// Returns: `void`.
  /// Side effects: Updates widget state; resets the move-mode transform.
  /// Notes: The selection is kept; it simply is not drawn while the filter
  /// hides its node.
  void _setFilter(ServiceTopologyFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _focusedRouteId = null;
    });
    _transform.value = Matrix4.identity();
  }

  /// Purpose: Open the filter sheet.
  /// Inputs: None.
  /// Returns: `Future<void>` that completes when the sheet closes.
  /// Side effects: Shows a modal bottom sheet whose changes apply live.
  /// Notes: Offers the devices that host at least one service, by name.
  Future<void> _openFilters() {
    final devices = [
      for (final device in widget.devices)
        if (widget.services.any((service) => service.deviceId == device.id))
          device,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TopologyFilterSheet(
        filter: _filter,
        devices: devices,
        onChanged: _setFilter,
      ),
    );
  }

  /// Purpose: Show a node's details in a bottom sheet.
  /// Inputs: `node`.
  /// Returns: `void`.
  /// Side effects: Shows a modal bottom sheet; its actions close it and call
  /// the page's editor callbacks.
  /// Notes: Used where the window has no room for the details pane. A route
  /// row opens the route's editor.
  void _showDetailsSheet(ServiceTopologyNode node) {
    final related = relatedRoutesForNode(
      node,
      _visible().routes,
      services: widget.services,
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: _TopologyNodeDetails(
          key: const Key('topology-details-sheet'),
          node: node,
          services: widget.services,
          devices: widget.devices,
          routes: related,
          shrinkWrap: true,
          onRouteTap: (route) {
            Navigator.pop(sheetContext);
            widget.onEditRoute(route);
          },
          onEditService: (service) {
            Navigator.pop(sheetContext);
            widget.onEditService(service);
          },
          onAddAccess: (service) {
            Navigator.pop(sheetContext);
            widget.onAddAccess(
              draft: ServiceAccessDraft(sourceServiceId: service.id),
            );
          },
        ),
      ),
    );
  }

  /// Purpose: Export topology image to an external representation.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild; shares the
  /// PNG through `ImageShareService`.
  /// Notes: The capture includes the current highlight, so a selected route
  /// can be exported on its own.
  Future<void> _exportTopologyImage() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_layoutReady) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.serviceTopology)));
      return;
    }
    setState(() => _exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Topology image boundary is not available.');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) {
        throw StateError('Topology image encoding failed.');
      }
      if (!mounted) return;
      await ImageShareService.sharePngBytes(
        context,
        bytes,
        fileName: 'mydevice_topology.png',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Purpose: Build the topology page scaffold.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None; `_visible` and `_selectionIn` only fill their caches.
  /// Notes: App bar: filters (with a badge counting the active parts), the
  /// "Group by device" toggle (resets the move-mode transform), rotation,
  /// export. Body: the mode row, the legend strip and the canvas;
  /// on `useDetailTwoPane` windows the details pane sits to the right at
  /// `topologyDetailPaneWidth`, present even with nothing selected so a
  /// selection never changes the canvas width and forces a relayout.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = _visible();
    final selection = _selectionIn(visible.graph, visible.routes);
    final size = MediaQuery.sizeOf(context);
    final canExport = _layoutReady && !visible.graph.isEmpty;
    final topology = Column(
      children: [
        _buildModeRow(l10n),
        _buildLegendStrip(l10n, selection?.node),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: visible.graph.isEmpty
                ? _buildNoMatch(l10n)
                : _ServiceTopologyView(
                    key: _viewKey,
                    graph: visible.graph,
                    services: widget.services,
                    devices: widget.devices,
                    routes: visible.routes,
                    options: ServiceTopologyLayoutOptions(
                      groupByDevice: _groupByDevice,
                    ),
                    mode: _mode,
                    quarterTurns: _quarterTurns,
                    repaintBoundaryKey: _captureKey,
                    onLayoutReadyChanged: (ready) {
                      if (_layoutReady == ready) return;
                      setState(() => _layoutReady = ready);
                    },
                    highlight: selection?.highlight,
                    selectedNodeId: selection?.node.id,
                    onNodeTap: _selectNode,
                    onBackgroundTap: selection == null ? null : _clearSelection,
                    transformationController: _transform,
                  ),
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.serviceTopology),
        actions: [
          IconButton(
            key: const Key('topology-filter'),
            tooltip: l10n.serviceTopologyFilters,
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: _filter.isActive,
              label: Text('${_filter.activeCount}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
          IconButton(
            key: const Key('topology-group-by-device'),
            tooltip: l10n.serviceTopologyGroupByDevice,
            isSelected: _groupByDevice,
            onPressed: () {
              setState(() => _groupByDevice = !_groupByDevice);
              _transform.value = Matrix4.identity();
            },
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
          ),
          IconButton(
            tooltip: l10n.serviceRotateTopology,
            onPressed: () {
              setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
              _transform.value = Matrix4.identity();
            },
            icon: const Icon(Icons.screen_rotation_alt),
          ),
          IconButton(
            tooltip: l10n.serviceExportTopologyImage,
            onPressed: _exporting || !canExport ? null : _exportTopologyImage,
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined),
          ),
        ],
      ),
      body: useDetailTwoPane(size.width, size.height)
          ? LayoutBuilder(
              builder: (context, constraints) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: topology),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: topologyDetailPaneWidth(constraints.maxWidth),
                    child: _buildDetailsPane(l10n, selection),
                  ),
                ],
              ),
            )
          : topology,
    );
  }

  /// Purpose: Build the mode row: the select / move switch, and Fit and Reset
  /// in move mode.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Fit asks the view to fit the canvas; Reset returns the viewer to
  /// the identity transform. Both are icon buttons with tooltips, so the row
  /// still fits a 412 dp phone; the row scrolls sideways on anything
  /// narrower.
  Widget _buildModeRow(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          SegmentedButton<_TopologyInteractionMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _TopologyInteractionMode.select,
                icon: const Icon(Icons.touch_app),
                label: Text(l10n.serviceTopologySelectMode),
              ),
              ButtonSegment(
                value: _TopologyInteractionMode.move,
                icon: const Icon(Icons.open_with),
                label: Text(l10n.serviceTopologyMoveMode),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selected) {
              setState(() => _mode = selected.single);
            },
          ),
          if (_mode == _TopologyInteractionMode.move) ...[
            const SizedBox(width: 4),
            IconButton(
              key: const Key('topology-fit'),
              tooltip: l10n.serviceTopologyFit,
              onPressed: () => _viewKey.currentState?.fitToViewport(),
              icon: const Icon(Icons.fit_screen),
            ),
            IconButton(
              key: const Key('topology-reset'),
              tooltip: l10n.serviceTopologyReset,
              onPressed: () => _transform.value = Matrix4.identity(),
              icon: const Icon(Icons.restart_alt),
            ),
          ],
        ],
      ),
    );
  }

  /// Purpose: Build the legend strip under the mode row.
  /// Inputs: `l10n`; `selected` — the selected node, if any.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: The legend toggle expands `ServiceTopologyLegend`; with a
  /// selection, a chip names the node and its delete button clears it. The
  /// strip is outside the canvas, so it is never exported.
  Widget _buildLegendStrip(
    AppLocalizations l10n,
    ServiceTopologyNode? selected,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                key: const Key('topology-legend-toggle'),
                onPressed: () => setState(() => _legendOpen = !_legendOpen),
                icon: Icon(_legendOpen ? Icons.expand_less : Icons.expand_more),
                label: Text(l10n.serviceTopologyLegend),
              ),
              if (selected != null)
                InputChip(
                  key: const Key('topology-selection-chip'),
                  avatar: const Icon(Icons.filter_center_focus, size: 18),
                  label: Text(
                    l10n.serviceTopologySelected(selected.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: _clearSelection,
                  deleteButtonTooltipMessage:
                      l10n.serviceTopologyClearSelection,
                ),
            ],
          ),
          if (_legendOpen)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: ServiceTopologyLegend(key: Key('topology-legend')),
            ),
        ],
      ),
    );
  }

  /// Purpose: Build the details pane of a split window.
  /// Inputs: `l10n`; `selection` — from `_selectionIn`, or null.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Non-modal. With nothing selected it shows a hint (keyed
  /// `topology-details-empty`); otherwise the node details (keyed
  /// `topology-details-pane`), where a route row narrows the highlight and
  /// its edit button opens the route's editor.
  Widget _buildDetailsPane(
    AppLocalizations l10n,
    ({
      ServiceTopologyNode node,
      List<ServiceRoute> related,
      ServiceTopologyHighlight highlight,
    })?
    selection,
  ) {
    if (selection == null) {
      return Center(
        key: const Key('topology-details-empty'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.serviceTopologySelectNodeHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return _TopologyNodeDetails(
      key: const Key('topology-details-pane'),
      node: selection.node,
      services: widget.services,
      devices: widget.devices,
      routes: selection.related,
      focusedRouteId: _focusedRouteId,
      showFocusHint: selection.related.length > 1,
      onRouteTap: _toggleRouteFocus,
      onRouteEdit: widget.onEditRoute,
      onEditService: widget.onEditService,
      onAddAccess: (service) => widget.onAddAccess(
        draft: ServiceAccessDraft(sourceServiceId: service.id),
      ),
      onClose: _clearSelection,
    );
  }

  /// Purpose: Build the message shown when the filters leave nothing.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Offers "Clear filters" in place.
  Widget _buildNoMatch(AppLocalizations l10n) {
    return Center(
      key: const Key('topology-no-match'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.serviceTopologyNoMatch, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => _setFilter(const ServiceTopologyFilter()),
            child: Text(l10n.serviceTopologyFilterClear),
          ),
        ],
      ),
    );
  }
}

/// A topology node's details: the node, its device and service with their
/// actions, and the routes through it. Shown in the bottom sheet on phones
/// and in the side pane on split windows.
class _TopologyNodeDetails extends StatelessWidget {
  final ServiceTopologyNode node;
  final List<ServiceNode> services;
  final List<Device> devices;
  final List<ServiceRoute> routes;
  final String? focusedRouteId;
  final bool showFocusHint;
  final bool shrinkWrap;
  final ValueChanged<ServiceRoute> onRouteTap;
  final ValueChanged<ServiceRoute>? onRouteEdit;
  final ValueChanged<ServiceNode> onEditService;
  final ValueChanged<ServiceNode> onAddAccess;
  final VoidCallback? onClose;

  /// Purpose: Create the node details.
  /// Inputs: `node`; `services`, `devices` — to resolve the node's own;
  /// `routes` — the related routes; `focusedRouteId` — marked selected;
  /// `showFocusHint`; `shrinkWrap` — for the sheet; `onRouteTap`;
  /// `onRouteEdit` — adds an edit button per route (pane only);
  /// `onEditService`, `onAddAccess`; `onClose` — adds a close button (pane
  /// only).
  /// Returns: A new `_TopologyNodeDetails`.
  /// Side effects: None.
  /// Notes: None.
  const _TopologyNodeDetails({
    super.key,
    required this.node,
    required this.services,
    required this.devices,
    required this.routes,
    required this.onRouteTap,
    required this.onEditService,
    required this.onAddAccess,
    this.focusedRouteId,
    this.showFocusHint = false,
    this.shrinkWrap = false,
    this.onRouteEdit,
    this.onClose,
  });

  /// Purpose: Build the details list.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Role, lane, device category and access levels are localized.
  /// Route rows are keyed `topology-route-<id>`, their edit buttons
  /// `topology-route-edit-<id>`.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final device = node.deviceId == null
        ? null
        : devices.where((device) => device.id == node.deviceId).firstOrNull;
    final service = node.serviceId == null
        ? null
        : services.where((service) => service.id == node.serviceId).firstOrNull;
    final routeEdit = onRouteEdit;
    return ListView(
      shrinkWrap: shrinkWrap,
      padding: EdgeInsets.fromLTRB(16, onClose == null ? 0 : 8, 16, 16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            child: Icon(iconForTopologyNode(node, services, devices)),
          ),
          title: Text(node.label),
          subtitle: Text(
            [
              serviceTopologyRoleLabel(l10n, node.role),
              if (node.detail?.trim().isNotEmpty == true) node.detail!,
              if (node.lane != null) serviceAccessLaneLabel(l10n, node.lane!),
            ].join(' · '),
          ),
          trailing: onClose == null
              ? null
              : IconButton(
                  key: const Key('topology-details-close'),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
        ),
        if (device != null)
          ListTile(
            leading: Icon(deviceCategoryIcon(device.category)),
            title: Text(device.name),
            subtitle: Text(deviceCategoryLabel(l10n, device.category)),
          ),
        if (service != null) ...[
          ListTile(
            leading: Icon(iconForService(service)),
            title: Text(service.name),
            subtitle: Text(
              service.endpoints
                  .map(
                    (endpoint) =>
                        '${endpoint.protocol.name}/${endpoint.portText}',
                  )
                  .join(', '),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => onEditService(service),
                icon: const Icon(Icons.edit_outlined),
                label: Text(l10n.editService),
              ),
              OutlinedButton.icon(
                onPressed: () => onAddAccess(service),
                icon: const Icon(Icons.add_link),
                label: Text(l10n.serviceAddAccess),
              ),
            ],
          ),
        ],
        if (routes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.serviceRoutes,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (showFocusHint)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.serviceTopologyRouteFocusHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final route in routes)
            ListTile(
              key: ValueKey('topology-route-${route.id}'),
              selected: route.id == focusedRouteId,
              leading: Icon(iconForRouteMethod(primaryRouteMethod(route))),
              title: Text(serviceRouteDisplayTarget(route)),
              subtitle: Text(
                [
                  serviceRouteTargetsSummary(route),
                  serviceAccessLevelLabel(l10n, route.accessLevel),
                  serviceAccessLaneLabel(
                    l10n,
                    serviceAccessLaneForRoute(route),
                  ),
                ].where((part) => part.isNotEmpty).join(' · '),
              ),
              trailing: routeEdit == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      key: ValueKey('topology-route-edit-${route.id}'),
                      tooltip: l10n.editServiceRoute,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => routeEdit(route),
                    ),
              onTap: () => onRouteTap(route),
            ),
        ],
      ],
    );
  }
}

/// The filter sheet: search text, lane chips and device chips, applied live.
class _TopologyFilterSheet extends StatefulWidget {
  final ServiceTopologyFilter filter;
  final List<Device> devices;
  final ValueChanged<ServiceTopologyFilter> onChanged;

  /// Purpose: Create the filter sheet.
  /// Inputs: `filter` — the filter it starts from; `devices` — the device
  /// chips to offer; `onChanged` — receives every change.
  /// Returns: A new `_TopologyFilterSheet`.
  /// Side effects: None.
  /// Notes: None.
  const _TopologyFilterSheet({
    required this.filter,
    required this.devices,
    required this.onChanged,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `_TopologyFilterSheetState`.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<_TopologyFilterSheet> createState() => _TopologyFilterSheetState();
}

class _TopologyFilterSheetState extends State<_TopologyFilterSheet> {
  late ServiceTopologyFilter _filter = widget.filter;
  late final TextEditingController _search = TextEditingController(
    text: widget.filter.query,
  );

  /// Purpose: Release the search controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the controller.
  /// Notes: None.
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Purpose: Apply a change locally and to the page.
  /// Inputs: `next`.
  /// Returns: `void`.
  /// Side effects: Updates widget state; calls `onChanged`.
  /// Notes: None.
  void _update(ServiceTopologyFilter next) {
    setState(() => _filter = next);
    widget.onChanged(next);
  }

  /// Purpose: Build the sheet.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: The last selected lane cannot be turned off. Clearing the last
  /// device chip means every device again, as does "All devices". Keys:
  /// `topology-filter-search`, `topology-filter-lane-<lane>`,
  /// `topology-filter-all-devices`, `topology-filter-device-<id>`,
  /// `topology-filter-clear`.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.serviceTopologyFilters,
                      style: text.titleLarge,
                    ),
                  ),
                  TextButton(
                    key: const Key('topology-filter-clear'),
                    onPressed: _filter.isActive
                        ? () {
                            _search.clear();
                            _update(const ServiceTopologyFilter());
                          }
                        : null,
                    child: Text(l10n.serviceTopologyFilterClear),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('topology-filter-search'),
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.serviceTopologyFilterSearch,
                ),
                onChanged: (value) => _update(_filter.copyWith(query: value)),
              ),
              const SizedBox(height: 16),
              Text(l10n.serviceTopologyFilterLanes, style: text.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final lane in ServiceAccessLane.values)
                    FilterChip(
                      key: ValueKey('topology-filter-lane-${lane.name}'),
                      showCheckmark: false,
                      avatar: Icon(
                        Icons.circle,
                        size: 12,
                        color: serviceAccessLaneColor(cs, lane),
                      ),
                      label: Text(serviceAccessLaneLabel(l10n, lane)),
                      selected: _filter.lanes.contains(lane),
                      onSelected: (on) {
                        final lanes = {..._filter.lanes};
                        on ? lanes.add(lane) : lanes.remove(lane);
                        if (lanes.isEmpty) return;
                        _update(_filter.copyWith(lanes: lanes));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l10n.serviceTopologyFilterDevices, style: text.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    key: const Key('topology-filter-all-devices'),
                    label: Text(l10n.serviceTopologyFilterAllDevices),
                    selected: _filter.deviceIds == null,
                    onSelected: (_) =>
                        _update(_filter.copyWith(clearDeviceIds: true)),
                  ),
                  for (final device in widget.devices)
                    FilterChip(
                      key: ValueKey('topology-filter-device-${device.id}'),
                      avatar: Icon(
                        deviceCategoryIcon(device.category),
                        size: 18,
                      ),
                      label: Text(device.name),
                      selected: _filter.deviceIds?.contains(device.id) ?? false,
                      onSelected: (on) {
                        final ids = {...?_filter.deviceIds};
                        on ? ids.add(device.id) : ids.remove(device.id);
                        _update(
                          ids.isEmpty
                              ? _filter.copyWith(clearDeviceIds: true)
                              : _filter.copyWith(deviceIds: ids),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
